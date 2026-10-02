import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';

class WeeklyActivitySection extends StatelessWidget {
  const WeeklyActivitySection({
    required this.weekActivity,
    required this.streakCount,
    this.isLoading = false,
    this.currentDate,
    super.key,
  });

  final Map<String, bool> weekActivity;
  final int streakCount;
  final bool isLoading;
  final DateTime? currentDate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = currentDate ?? DateTime.now();
    final currentDayIndex = now.weekday - 1;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        streakCount > 0
                            ? '$streakCount-Session Consistency'
                            : 'Weekly Activity',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    'Week ${DateFormat('w').format(now)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isCompleted = weekActivity[dayNames[index]] ?? false;
              final isToday = index == currentDayIndex;
              final isMissed = index < currentDayIndex && !isCompleted;

              return Column(
                children: [
                  Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isMissed
                          ? AppColors.error
                          : isToday
                          ? AppColors.primary
                          : (isDark ? Colors.white54 : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    key: ValueKey('weekly-activity-${dayNames[index]}'),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.success
                          : (isMissed
                                ? AppColors.error
                                : isToday
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.shade100)),
                      border: Border.all(
                        color: isToday
                            ? AppColors.primary
                            : (isCompleted
                                  ? AppColors.success
                                  : (isMissed
                                        ? AppColors.error
                                        : (isDark
                                              ? Colors.white12
                                              : Colors.grey.shade300))),
                        width: isToday ? 2.0 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : (isMissed
                                ? const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : (isToday
                                      ? Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : null)),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

typedef WeeklyStreakWidget = WeeklyActivitySection;
