import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A sleek, centered modal dialog that confirms a workout activity or set has been added or updated.
class WorkoutActivitySuccessDialog extends StatelessWidget {
  final String exerciseName;
  final int setNumber;
  final double weight;
  final int reps;
  final double rir;
  final bool isEdit;
  final bool isDelete;
  final VoidCallback onDismiss;

  const WorkoutActivitySuccessDialog({
    required this.exerciseName,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.rir,
    required this.onDismiss,
    this.isEdit = false,
    this.isDelete = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),

            // Dialog Title
            Text(
              isDelete
                  ? 'Workout Activity Deleted'
                  : (isEdit ? 'Workout Set Updated' : 'Workout Activity Added'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Activity Info Summary Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    exerciseName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set $setNumber  •  ${weight > 0 ? '$weight kg × ' : ''}$reps reps  •  RIR $rir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // OK Confirmation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: onDismiss,
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to display the centered [WorkoutActivitySuccessDialog]
Future<void> showWorkoutActivitySuccessDialog({
  required BuildContext context,
  required String exerciseName,
  required int setNumber,
  required double weight,
  required int reps,
  required double rir,
  bool isEdit = false,
  bool isDelete = false,
  VoidCallback? onDismiss,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => WorkoutActivitySuccessDialog(
      exerciseName: exerciseName,
      setNumber: setNumber,
      weight: weight,
      reps: reps,
      rir: rir,
      isEdit: isEdit,
      isDelete: isDelete,
      onDismiss: () {
        Navigator.of(dialogContext).pop();
        onDismiss?.call();
      },
    ),
  );
}
