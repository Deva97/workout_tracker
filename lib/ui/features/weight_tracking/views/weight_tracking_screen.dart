import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/compact_sync_button.dart';
import 'package:workout_tracker/ui/core/widgets/modular_card.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';
import '../view_models/weight_tracking_view_model.dart';
import 'widgets/weight_trend_chart.dart';

class WeightTrackingScreen extends StatefulWidget {
  final WeightTrackingViewModel? viewModel;

  const WeightTrackingScreen({this.viewModel, super.key});

  @override
  State<WeightTrackingScreen> createState() => _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends State<WeightTrackingScreen> {
  late final WeightTrackingViewModel _viewModel;
  bool _createdOwnViewModel = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _viewModel = WeightTrackingViewModel();
      _createdOwnViewModel = true;
    }
    _viewModel.initialize();
  }

  @override
  void dispose() {
    if (_createdOwnViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Weight Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(
              child: CompactSyncButton(),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          // State 1: Minimalist Loader while verifying Google Drive sheet
          if (_viewModel.isCheckingDrive) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checking Drive for Body_weight.xlsx...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          // State 2: Missing Body_weight.xlsx prompt
          if (!_viewModel.sheetExists) {
            return _buildMissingSheetPrompt();
          }

          // State 3: Active Dashboard
          return RefreshIndicator(
            onRefresh: _viewModel.loadRecords,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Today's Weight Hero Card
                _buildTodayWeightCard(),
                const SizedBox(height: 16),

                // Graph Mode Selector Pills
                _buildGraphModeSelector(),
                const SizedBox(height: 12),

                // Interactive Weight Trend Chart
                WeightTrendChart(
                  dailyRecords: _viewModel.records,
                  weeklyAverages: _viewModel.weeklyAverages,
                  mode: _viewModel.graphMode,
                ),
                const SizedBox(height: 16),

                // Metric Summary Row
                _buildMetricSummaryRow(),
                const SizedBox(height: 20),

                // Recent History Header & List
                const Text(
                  'Recent Measurements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildRecentHistoryList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMissingSheetPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Initialize Weight Tracker',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Body_weight.xlsx was not found in your Google Drive folder. Add this sheet to track your daily weight and view weekly averages.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: _viewModel.isCreatingSheet
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_rounded, size: 20),
                label: Text(_viewModel.isCreatingSheet ? 'Creating Sheet...' : 'Add Body_weight.xlsx'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _viewModel.isCreatingSheet ? null : _viewModel.createSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayWeightCard() {
    final today = _viewModel.todayRecord;
    final hasLoggedToday = today != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (hasLoggedToday ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasLoggedToday ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
                  size: 22,
                  color: hasLoggedToday ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hasLoggedToday
                                ? "Today's Weight: ${today.weight.toStringAsFixed(1)} kg"
                                : "Today's Weight",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? AppColors.textLight : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        hasLoggedToday
                            ? StatusBadge.tag(label: 'LOGGED', color: AppColors.success)
                            : StatusBadge.tag(label: 'PENDING', color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasLoggedToday
                          ? 'Logged via scale photo at ${DateFormat('h:mm a').format(today.date)}'
                          : 'Capture a scale photo to log your weight for today',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _viewModel.isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      hasLoggedToday ? Icons.refresh_rounded : Icons.camera_alt_outlined,
                      size: 18,
                    ),
              label: Text(
                hasLoggedToday ? 'Retake Scale Photo' : 'Log Today’s Weight (Camera)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _viewModel.isScanning ? null : () => _viewModel.captureAndLogWeight(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeFilterChip(
            label: 'Everyday Graph',
            icon: Icons.show_chart_rounded,
            isSelected: _viewModel.graphMode == WeightGraphMode.daily,
            onTap: () => _viewModel.toggleGraphMode(WeightGraphMode.daily),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeFilterChip(
            label: 'Weekly Average',
            icon: Icons.bar_chart_rounded,
            isSelected: _viewModel.graphMode == WeightGraphMode.weeklyAverage,
            onTap: () => _viewModel.toggleGraphMode(WeightGraphMode.weeklyAverage),
          ),
        ),
      ],
    );
  }

  Widget _buildModeFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textLight : AppColors.textPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSummaryRow() {
    final records = _viewModel.records;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String currentStr = records.isNotEmpty ? '${records.last.weight.toStringAsFixed(1)} kg' : '--';
    String deltaStr = '--';
    Color deltaColor = AppColors.textSecondary;

    if (_viewModel.weeklyDelta != null) {
      final delta = _viewModel.weeklyDelta!;
      if (delta > 0) {
        deltaStr = '+${delta.toStringAsFixed(1)} kg';
        deltaColor = AppColors.warning;
      } else if (delta < 0) {
        deltaStr = '${delta.toStringAsFixed(1)} kg';
        deltaColor = AppColors.success;
      } else {
        deltaStr = '0.0 kg';
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Current Weight',
            value: currentStr,
            icon: Icons.speed_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Weekly Change',
            value: deltaStr,
            icon: Icons.trending_up_rounded,
            color: deltaColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistoryList() {
    final reversed = _viewModel.records.reversed.toList();
    if (reversed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No records logged yet.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: reversed.take(10).map((record) {
        final dateStr = DateFormat('EEE, MMM d, yyyy').format(record.date);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ModularCard(
            title: '${record.weight.toStringAsFixed(1)} kg',
            subtitle: dateStr,
            icon: Icons.monitor_weight_outlined,
            iconColor: AppColors.primary,
            iconBackgroundColor: AppColors.primary.withValues(alpha: 0.1),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
              onPressed: () => _confirmDelete(record.id, record.weight),
            ),
            onTap: () {},
          ),
        );
      }).toList(),
    );
  }

  Future<void> _confirmDelete(String id, double weight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Weight Record?'),
        content: Text('Are you sure you want to delete the reading of ${weight.toStringAsFixed(1)} kg?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _viewModel.deleteRecord(id);
    }
  }
}
