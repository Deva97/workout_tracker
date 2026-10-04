import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/daily_workout_entry.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/domain/repositories/auth_repository.dart' show SyncState;
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/empty_state_widget.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';
import 'package:workout_tracker/ui/core/widgets/workout_delete_confirm_dialog.dart';
import 'package:workout_tracker/ui/core/widgets/sync_failure_dialog.dart';
import 'package:workout_tracker/ui/core/widgets/workout_activity_success_dialog.dart';
import '../view_models/todays_workout_log_view_model.dart';
import 'widgets/add_workout_set_modal.dart';
import 'widgets/boundary_shake_wrapper.dart';
import 'widgets/date_navigator_bar.dart';
import 'widgets/half_screen_page_scroll_physics.dart';

class TodaysWorkoutLogScreen extends StatefulWidget {
  final TodaysWorkoutLogViewModel? viewModel;

  const TodaysWorkoutLogScreen({
    this.viewModel,
    super.key,
  });

  @override
  State<TodaysWorkoutLogScreen> createState() => _TodaysWorkoutLogScreenState();
}

class _TodaysWorkoutLogScreenState extends State<TodaysWorkoutLogScreen> {
  late final TodaysWorkoutLogViewModel _viewModel;
  late final PageController _pageController;
  final BoundaryShakeController _boundaryShakeController = BoundaryShakeController();

  bool _createdOwnViewModel = false;
  DateTime? _lastBoundaryVibrationTime;
  double _accumulatedHorizontalOverscroll = 0.0;
  bool _hasTriggeredBoundaryInCurrentDrag = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _viewModel = TodaysWorkoutLogViewModel();
      _createdOwnViewModel = true;
    }

    _pageController = PageController(
      initialPage: _viewModel.currentDateIndex >= 0 ? _viewModel.currentDateIndex : 0,
    );

    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadTodaysWorkoutLog();
    });
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {});

    if (_pageController.hasClients) {
      final isScrolling = _pageController.position.isScrollingNotifier.value;
      final currentPage = _pageController.page?.round() ?? 0;
      final targetPage = _viewModel.currentDateIndex;
      if (!isScrolling && targetPage >= 0 && currentPage != targetPage) {
        _pageController.jumpToPage(targetPage);
      }
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _pageController.dispose();
    if (_createdOwnViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  void _triggerBoundaryFeedback() {
    final now = DateTime.now();
    if (_lastBoundaryVibrationTime == null ||
        now.difference(_lastBoundaryVibrationTime!) > const Duration(milliseconds: 350)) {
      _lastBoundaryVibrationTime = now;
      _boundaryShakeController.triggerBoundaryFeedback();
    }
  }

  Future<void> _deleteRecord(DailyWorkoutEntry entry) async {
    final deletedRecord = entry.record;

    // Step 1: Confirmation modal with Cancel or OK
    final confirmed = await showWorkoutDeleteConfirmDialog(
      context: context,
      exerciseName: entry.exercise.name,
      setNumber: deletedRecord.set,
      weight: deletedRecord.weight,
      reps: deletedRecord.reps,
      rir: deletedRecord.rir,
    );

    if (confirmed != true) return; // User tapped Cancel or dismissed

    // Step 2: User tapped OK -> Delete and sync immediately
    await _executeDeleteWithSync(entry);
  }

  Future<void> _executeDeleteWithSync(DailyWorkoutEntry entry) async {
    final deletedRecord = entry.record;
    final syncResult = await _viewModel.deleteSetAndSync(entry);

    if (!mounted) return;

    if (syncResult == SyncState.synced) {
      showWorkoutActivitySuccessDialog(
        context: context,
        exerciseName: entry.exercise.name,
        setNumber: deletedRecord.set,
        weight: deletedRecord.weight,
        reps: deletedRecord.reps,
        rir: deletedRecord.rir,
        isDelete: true,
      );
    } else {
      _showDeleteFailureDialog(entry);
    }
  }

  void _showDeleteFailureDialog(DailyWorkoutEntry entry) {
    if (!mounted) return;
    final deletedRecord = entry.record;
    showSyncFailureDialog(
      context: context,
      title: 'Sync Failed',
      message: 'Failed to sync deletion with the database. Would you like to retry or cancel?',
      onRetry: () async {
        final retryResult = await _viewModel.retrySync();
        if (!mounted) return;
        if (retryResult == SyncState.synced) {
          showWorkoutActivitySuccessDialog(
            context: context,
            exerciseName: entry.exercise.name,
            setNumber: deletedRecord.set,
            weight: deletedRecord.weight,
            reps: deletedRecord.reps,
            rir: deletedRecord.rir,
            isDelete: true,
          );
        } else {
          _showDeleteFailureDialog(entry);
        }
      },
      onCancel: () async {
        // Rollback: restore deleted set so it remains on the page!
        await _viewModel.rollbackDeletedSet(deletedRecord);
      },
    );
  }

  Future<void> _executeSaveWithSync(DailyRecord record, {required bool keepOpen}) async {
    final syncResult = await _viewModel.saveSetAndSync(record);

    if (!mounted) return;

    if (syncResult == SyncState.synced) {
      showWorkoutActivitySuccessDialog(
        context: context,
        exerciseName: record.workoutName,
        setNumber: record.set,
        weight: record.weight,
        reps: record.reps,
        rir: record.rir,
        isEdit: false,
      );
    } else {
      _showSaveFailureDialog(record, keepOpen: keepOpen);
    }
  }

  void _showSaveFailureDialog(DailyRecord record, {required bool keepOpen}) {
    if (!mounted) return;
    showSyncFailureDialog(
      context: context,
      title: 'Sync Failed',
      message: 'Failed to sync new workout set with the database. Would you like to retry or cancel?',
      onRetry: () async {
        final retryResult = await _viewModel.retrySync();
        if (!mounted) return;
        if (retryResult == SyncState.synced) {
          showWorkoutActivitySuccessDialog(
            context: context,
            exerciseName: record.workoutName,
            setNumber: record.set,
            weight: record.weight,
            reps: record.reps,
            rir: record.rir,
            isEdit: false,
          );
        } else {
          _showSaveFailureDialog(record, keepOpen: keepOpen);
        }
      },
      onCancel: () async {
        // Rollback: cancel the operation so workout log is NOT seen on the page!
        await _viewModel.rollbackAddedSet(record);
      },
    );
  }

  Future<void> _executeEditWithSync(DailyRecord record, {required DailyRecord previousRecord}) async {
    final syncResult = await _viewModel.editSetAndSync(record);

    if (!mounted) return;

    if (syncResult == SyncState.synced) {
      showWorkoutActivitySuccessDialog(
        context: context,
        exerciseName: record.workoutName,
        setNumber: record.set,
        weight: record.weight,
        reps: record.reps,
        rir: record.rir,
        isEdit: true,
      );
    } else {
      _showEditFailureDialog(record, previousRecord: previousRecord);
    }
  }

  void _showEditFailureDialog(DailyRecord record, {required DailyRecord previousRecord}) {
    if (!mounted) return;
    showSyncFailureDialog(
      context: context,
      title: 'Sync Failed',
      message: 'Failed to sync updated set with the database. Would you like to retry or cancel?',
      onRetry: () async {
        final retryResult = await _viewModel.retrySync();
        if (!mounted) return;
        if (retryResult == SyncState.synced) {
          showWorkoutActivitySuccessDialog(
            context: context,
            exerciseName: record.workoutName,
            setNumber: record.set,
            weight: record.weight,
            reps: record.reps,
            rir: record.rir,
            isEdit: true,
          );
        } else {
          _showEditFailureDialog(record, previousRecord: previousRecord);
        }
      },
      onCancel: () async {
        await _viewModel.rollbackEditedSet(previousRecord);
      },
    );
  }

  Future<void> _triggerManualSync() async {
    final result = await _viewModel.manualSync();
    if (!mounted) return;

    if (result == SyncState.synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Synced with Google Drive Excel!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sync failed. Changes saved locally in cache.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _openDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.selectedDate.isAfter(now) ? now : _viewModel.selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'SELECT WORKOUT DATE',
      confirmText: 'VIEW LOG',
    );

    if (picked != null) {
      await _viewModel.changeDate(picked);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_viewModel.currentDateIndex);
      }
    }
  }

  void _openAddSetModal([Exercise? targetExercise, DailyRecord? editRecord]) {
    int nextSetNumber = 1;
    DailyRecord? previousRecord;

    final effectiveExercise = targetExercise ??
        (_viewModel.availableExercises.isNotEmpty ? _viewModel.availableExercises.first : null);

    if (effectiveExercise != null && editRecord == null) {
      final existingSets = _viewModel.todaysEntries
          .where((entry) => entry.exercise.guid == effectiveExercise.guid)
          .map((entry) => entry.record.set);
      if (existingSets.isNotEmpty) {
        nextSetNumber = existingSets.reduce((a, b) => a > b ? a : b) + 1;
      }
      previousRecord = _viewModel.getLastRecordedSet(effectiveExercise.guid);
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
          availableExercises: _viewModel.availableExercises,
          initialExercise: targetExercise,
          initialSetNumber: editRecord?.set ?? nextSetNumber,
          editRecord: editRecord,
          previousRecord: previousRecord,
          targetDate: _viewModel.selectedDate,
          getPreviousRecord: (guid) => _viewModel.getLastRecordedSet(guid),
          onSaveSet: (record, keepOpen) async {
            if (editRecord != null) {
              await _executeEditWithSync(record, previousRecord: editRecord);
            } else {
              await _executeSaveWithSync(record, keepOpen: keepOpen);
            }
          },
        ),
      ),
    );
  }

  Map<String, List<DailyWorkoutEntry>> _groupEntries(List<DailyWorkoutEntry> entries) {
    final Map<String, List<DailyWorkoutEntry>> grouped = {};
    for (final entry in entries) {
      final key = entry.exercise.guid;
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayFormatted = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Workout Log', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(
              _viewModel.isViewingToday
                  ? todayFormatted.toUpperCase()
                  : DateFormat('EEEE, MMM d').format(_viewModel.selectedDate).toUpperCase(),
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
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: ValueListenableBuilder<SyncState>(
                valueListenable: _viewModel.syncStateListenable,
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
      body: BoundaryShakeWrapper(
        controller: _boundaryShakeController,
        child: Column(
          children: [
            // Top Date Navigation Bar (< Date >)
            RepaintBoundary(
              child: DateNavigatorBar(
                selectedDate: _viewModel.selectedDate,
                isViewingToday: _viewModel.isViewingToday,
                canGoPrevious: _viewModel.canGoPrevious,
                canGoNext: _viewModel.canGoNext,
                onPreviousPressed: () {
                  if (_viewModel.canGoPrevious) {
                    _pageController.animateToPage(
                      _viewModel.currentDateIndex + 1,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _triggerBoundaryFeedback();
                  }
                },
                onNextPressed: () {
                  if (_viewModel.canGoNext) {
                    _pageController.animateToPage(
                      _viewModel.currentDateIndex - 1,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _triggerBoundaryFeedback();
                  }
                },
                onDatePickerPressed: _openDatePicker,
                onTodayPressed: () {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOut,
                  );
                },
                onBoundaryAttempt: _triggerBoundaryFeedback,
              ),
            ),

            // Horizontal PageView for scrolling between dates
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _viewModel.changeDate(_viewModel.selectedDate),
                child: _viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // Only handle horizontal scroll events originating directly from the PageView (depth == 0).
                          // Descendant vertical scrolling from inner lists is ignored to eliminate stray vibrations.
                          if (notification.depth == 0 && notification.metrics.axis == Axis.horizontal) {
                            if (notification is OverscrollNotification) {
                              _accumulatedHorizontalOverscroll += notification.overscroll;
                              const double overscrollThreshold = 48.0;

                              if (!_hasTriggeredBoundaryInCurrentDrag &&
                                  _accumulatedHorizontalOverscroll.abs() >= overscrollThreshold) {
                                if (_accumulatedHorizontalOverscroll < 0 && !_viewModel.canGoNext) {
                                  _hasTriggeredBoundaryInCurrentDrag = true;
                                  _triggerBoundaryFeedback();
                                } else if (_accumulatedHorizontalOverscroll > 0 && !_viewModel.canGoPrevious) {
                                  _hasTriggeredBoundaryInCurrentDrag = true;
                                  _triggerBoundaryFeedback();
                                }
                              }
                            } else if (notification is ScrollEndNotification ||
                                (notification is UserScrollNotification &&
                                    notification.direction == ScrollDirection.idle)) {
                              _accumulatedHorizontalOverscroll = 0.0;
                              _hasTriggeredBoundaryInCurrentDrag = false;
                            }
                          }
                          return false;
                        },
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const HalfScreenPageScrollPhysics(),
                          itemCount: _viewModel.availableDates.length,
                          onPageChanged: (index) {
                            if (index >= 0 && index < _viewModel.availableDates.length) {
                              final newDate = _viewModel.availableDates[index];
                              _viewModel.changeDate(newDate);
                            }
                          },
                          itemBuilder: (context, index) {
                            final pageDate = _viewModel.availableDates[index];
                            final isPageToday = _viewModel.isSameDay(pageDate, DateTime.now());
                            final entries = _viewModel.isSameDay(pageDate, _viewModel.selectedDate)
                                ? _viewModel.todaysEntries
                                : _viewModel.getEntriesForDate(pageDate);

                            if (entries.isEmpty) {
                              final dateLabel = isPageToday
                                  ? 'Today'
                                  : DateFormat('EEEE, MMM d').format(pageDate);
                              return RepaintBoundary(
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: Container(
                                    height: MediaQuery.of(context).size.height * 0.65,
                                    padding: const EdgeInsets.all(16),
                                    child: EmptyStateWidget(
                                      icon: Icons.fitness_center_rounded,
                                      title: isPageToday ? 'No Workout Logged Today' : 'No Workout on $dateLabel',
                                      description: isPageToday
                                          ? 'Track your workout sets, weights, reps, and RIR for today\'s session.'
                                          : 'No sets were recorded for this day. You can add sets retrospectively if needed.',
                                      buttonText: isPageToday ? 'Add First Workout Set' : 'Add Workout Set',
                                      onButtonPressed: () => _openAddSetModal(),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return RepaintBoundary(
                              child: _buildGroupedEntriesList(entries, isDark),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedEntriesList(List<DailyWorkoutEntry> entries, bool isDark) {
    final groupedEntries = _groupEntries(entries);
    final groupedList = groupedEntries.values.toList(growable: false);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
      itemCount: groupedList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final exerciseEntries = groupedList[index];
        final exercise = exerciseEntries.first.exercise;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sleek, Compact Exercise Header
              InkWell(
                onTap: () => _openAddSetModal(exercise),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      // Muscle Tag
                      if (exercise.bodyPart.isNotEmpty) ...[
                        StatusBadge.tag(
                          label: exercise.bodyPart.toUpperCase(),
                          color: AppColors.getMuscleColor(exercise.bodyPart),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Exercise Name
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Set count
                      Text(
                        '${exerciseEntries.length} ${exerciseEntries.length == 1 ? 'set' : 'sets'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),

                      // Quick Add Set Button
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        tooltip: 'Add set for ${exercise.name}',
                        onPressed: () => _openAddSetModal(exercise),
                      ),
                    ],
                  ),
                ),
              ),

              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
              ),

              // Compact Set Rows
              ...exerciseEntries.asMap().entries.map((entryItem) {
                final setIndex = entryItem.key;
                final entry = entryItem.value;
                final isPr = _viewModel.isPersonalRecord(entry);

                return Column(
                  children: [
                    if (setIndex > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 14,
                        endIndent: 14,
                        color: isDark
                            ? AppColors.cardBorderDark.withValues(alpha: 0.5)
                            : AppColors.cardBorderLight.withValues(alpha: 0.5),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Row(
                        children: [
                          // Set number pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SET ${entry.record.set}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                color: AppColors.primary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),

                          // PR Badge
                          if (isPr) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                'PR 🏆',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  color: Color(0xFFF59E0B),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(width: 8),

                          // Middle Metrics: Weight × Reps • RIR
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  if (entry.record.weight > 0) ...[
                                    TextSpan(
                                      text: '${entry.record.weight} kg',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark ? AppColors.textLight : AppColors.textPrimary,
                                      ),
                                    ),
                                    const TextSpan(text: ' × '),
                                  ],
                                  TextSpan(
                                    text: '${entry.record.reps} reps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark ? AppColors.textLight : AppColors.textPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  •  RIR ${entry.record.rir}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Actions: Compact Edit & Delete
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit set',
                                onPressed: () => _openAddSetModal(entry.exercise, entry.record),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(),
                                tooltip: 'Delete set',
                                onPressed: () => _deleteRecord(entry),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
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
  late final AnimationController _rotationController;

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
  void didUpdateWidget(covariant CompactSyncButton oldWidget) {
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
    final (label, color, icon) = switch (widget.syncState) {
      SyncState.synced => ('Synced', AppColors.success, Icons.cloud_done_rounded),
      SyncState.syncing => ('Syncing...', AppColors.primary, Icons.sync_rounded),
      SyncState.error => ('Sync', AppColors.warning, Icons.cloud_upload_rounded),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.syncState == SyncState.syncing ? null : widget.onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _rotationController,
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
