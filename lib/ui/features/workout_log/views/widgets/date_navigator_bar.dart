import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';

/// A date navigation bar for moving across workout records day-by-day,
/// jumping to today, or opening a date picker.
class DateNavigatorBar extends StatelessWidget {
  final DateTime selectedDate;
  final bool isViewingToday;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPreviousPressed;
  final VoidCallback onNextPressed;
  final VoidCallback onDatePickerPressed;
  final VoidCallback onTodayPressed;
  final VoidCallback onBoundaryAttempt;

  const DateNavigatorBar({
    required this.selectedDate,
    required this.isViewingToday,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPreviousPressed,
    required this.onNextPressed,
    required this.onDatePickerPressed,
    required this.onTodayPressed,
    required this.onBoundaryAttempt,
    super.key,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    } else if (diff == 1) {
      return 'Yesterday, ${DateFormat('MMM d').format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('EEE, MMM d').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateLabel = _formatDate(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Previous Record Button (<)
          IconButton(
            key: const Key('prev_date_button'),
            icon: Icon(
              Icons.chevron_left_rounded,
              color: canGoPrevious
                  ? AppColors.primary
                  : (isDark ? Colors.white24 : Colors.black26),
              size: 28,
            ),
            tooltip: canGoPrevious ? 'Previous Workout Record' : 'No earlier records',
            onPressed: canGoPrevious ? onPreviousPressed : onBoundaryAttempt,
          ),

          // Center Date Chip (Tappable to pick date)
          Expanded(
            child: InkWell(
              key: const Key('date_picker_chip'),
              onTap: onDatePickerPressed,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isViewingToday
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : (isDark
                          ? AppColors.surfaceDarkElevated
                          : AppColors.surfaceLightElevated),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isViewingToday
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : (isDark
                            ? AppColors.cardBorderDark
                            : AppColors.cardBorderLight),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: isViewingToday
                          ? AppColors.primary
                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isViewingToday
                              ? AppColors.primary
                              : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next Record Button (>)
          IconButton(
            key: const Key('next_date_button'),
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext
                  ? AppColors.primary
                  : (isDark ? Colors.white24 : Colors.black26),
              size: 28,
            ),
            tooltip: canGoNext ? 'Next Workout Record' : 'No later records',
            onPressed: canGoNext ? onNextPressed : onBoundaryAttempt,
          ),

          // Jump to Today button if looking at past record
          if (!isViewingToday) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              key: const Key('jump_to_today_button'),
              onPressed: onTodayPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}

