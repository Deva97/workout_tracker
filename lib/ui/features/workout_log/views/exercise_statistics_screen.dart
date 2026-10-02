import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/empty_state_widget.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';
import '../view_models/exercise_statistics_view_model.dart';
import 'widgets/strength_trend_chart.dart';

// Re-export ViewModel enums and classes for callers
export '../view_models/exercise_statistics_view_model.dart' show StatsViewMode, TimeFrameOption;

class ExerciseStatisticsScreen extends StatefulWidget {
  final String? initialExerciseGuid;
  final ExerciseStatisticsViewModel? viewModel;

  const ExerciseStatisticsScreen({
    this.initialExerciseGuid,
    this.viewModel,
    super.key,
  });

  @override
  State<ExerciseStatisticsScreen> createState() => _ExerciseStatisticsScreenState();
}

class _ExerciseStatisticsScreenState extends State<ExerciseStatisticsScreen> {
  late final ExerciseStatisticsViewModel _viewModel;
  bool _createdOwnViewModel = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _viewModel = ExerciseStatisticsViewModel();
      _createdOwnViewModel = true;
    }
    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.init(widget.initialExerciseGuid);
    });
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    if (_createdOwnViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Statistics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewModel.availableExercises.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: EmptyStateWidget(
                    icon: Icons.fitness_center_rounded,
                    title: 'No Exercises Found',
                    description: 'Add exercises in Exercise Directory to view strength progress.',
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Exercise Selector Dropdown (Exercise_DB)
                      Card(
                        elevation: 0,
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Exercise>(
                              value: _viewModel.selectedExercise,
                              isExpanded: true,
                              dropdownColor: Theme.of(context).cardColor,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                              hint: const Text('Select Exercise from Exercise_DB'),
                              items: _viewModel.availableExercises.map((e) {
                                return DropdownMenuItem<Exercise>(
                                  value: e,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                        ),
                                      ),
                                      if (e.bodyPart.isNotEmpty)
                                        StatusBadge.tag(
                                          label: e.bodyPart.toUpperCase(),
                                          color: AppColors.getMuscleColor(e.bodyPart),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (Exercise? selected) {
                                if (selected != null) {
                                  _viewModel.selectExercise(selected);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Timeframe Filter Chips Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ExerciseStatisticsViewModel.timeFrames.map((tf) {
                            final isSelected = _viewModel.selectedTimeFrame.label == tf.label;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(tf.label),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    _viewModel.selectTimeFrame(tf);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stat Summary Cards Grid (Always visible above graph & details)
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Peak Performance',
                              value: '${_viewModel.peakScore.toStringAsFixed(1)} pts',
                              icon: Icons.emoji_events_rounded,
                              iconColor: Colors.amber.shade700,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Strength Trend',
                              value: '${_viewModel.trendPercentage >= 0 ? '+' : ''}${_viewModel.trendPercentage.toStringAsFixed(1)}%',
                              icon: _viewModel.trendPercentage >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              iconColor: _viewModel.trendPercentage >= 0 ? Colors.green : AppColors.error,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Total Sessions',
                              value: '${_viewModel.totalSessionsInPeriod}',
                              icon: Icons.calendar_month_rounded,
                              iconColor: AppColors.primary,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Total Sets',
                              value: '${_viewModel.totalSetsInPeriod}',
                              icon: Icons.fitness_center_rounded,
                              iconColor: AppColors.accent,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // View Mode Switcher Segmented Control (Graph vs Details)
                      SegmentedButton<StatsViewMode>(
                        segments: const [
                          ButtonSegment<StatsViewMode>(
                            value: StatsViewMode.graph,
                            label: Text('Graph'),
                            icon: Icon(Icons.show_chart_rounded),
                          ),
                          ButtonSegment<StatsViewMode>(
                            value: StatsViewMode.details,
                            label: Text('Details'),
                            icon: Icon(Icons.table_rows_rounded),
                          ),
                        ],
                        selected: {_viewModel.currentViewMode},
                        onSelectionChanged: (newSelection) {
                          _viewModel.setViewMode(newSelection.first);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Content Switcher: Graph View vs Raw Details View
                      if (_viewModel.currentViewMode == StatsViewMode.graph)
                        _buildGraphView(isDark)
                      else
                        _buildDetailsView(isDark),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGraphView(bool isDark) {
    if (_viewModel.chartPoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          ),
        ),
        child: EmptyStateWidget(
          icon: Icons.show_chart_rounded,
          title: 'No Workout History Found',
          description:
              'No logged sets found for "${_viewModel.selectedExercise?.name ?? 'Selected Exercise'}" in the last ${_viewModel.selectedTimeFrame.label}.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metric Toggle Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ChartMetricType.values.map((metric) {
              final isSelected = _viewModel.selectedMetric == metric;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 12),
                child: FilterChip(
                  label: Text(metric.label),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : AppColors.textPrimary),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _viewModel.setSelectedMetric(metric);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        StrengthTrendChart(
          points: _viewModel.chartPoints,
          metricType: _viewModel.selectedMetric,
        ),
      ],
    );
  }

  Widget _buildDetailsView(bool isDark) {
    if (_viewModel.rawHistoryRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          ),
        ),
        child: EmptyStateWidget(
          icon: Icons.table_rows_rounded,
          title: 'No Workout History Found',
          description:
              'No logged sets found for "${_viewModel.selectedExercise?.name ?? 'Selected Exercise'}" in the last ${_viewModel.selectedTimeFrame.label}.',
        ),
      );
    }

    // Group raw records by date (newest first)
    final Map<String, List<DailyRecord>> grouped = {};
    for (final r in _viewModel.rawHistoryRecords.reversed) {
      final dateKey = DateFormat('yyyy-MM-dd').format(r.date);
      grouped.putIfAbsent(dateKey, () => []).add(r);
    }

    return Column(
      children: grouped.entries.map((group) {
        final dateRecords = group.value;
        final displayDate = DateFormat('EEEE, MMMM d, yyyy').format(dateRecords.first.date);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Header (Date & total sets)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.cardBorderDark : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    StatusBadge.tag(
                      label: '${dateRecords.length} ${dateRecords.length == 1 ? 'SET' : 'SETS'}',
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),

              // Sets list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: dateRecords.length,
                separatorBuilder: (_, _) => Divider(
                  height: 8,
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
                itemBuilder: (context, idx) {
                  final record = dateRecords[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Set number pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Set ${record.set}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),

                        // Weight, Reps, RIR Details
                        Row(
                          children: [
                            if (record.weight > 0) ...[
                              _buildDetailPill('Weight', '${record.weight} kg', isDark),
                              const SizedBox(width: 8),
                            ],
                            _buildDetailPill('Reps', '${record.reps}', isDark),
                            const SizedBox(width: 8),
                            _buildDetailPill('RIR', '${record.rir}', isDark),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailPill(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
