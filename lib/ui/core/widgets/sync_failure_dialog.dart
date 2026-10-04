import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A centered modal dialog displayed when syncing with Google Drive Excel fails.
/// Offers "Cancel" (which rolls back the local changes) and "Retry" (which re-attempts sync).
class SyncFailureDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const SyncFailureDialog({
    required this.onCancel,
    required this.onRetry,
    this.title = 'Sync Failed',
    this.message = 'Failed to sync changes with the database. Please check your network connection and try again.',
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
            // Error icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sync_problem_rounded,
                color: AppColors.error,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Message description
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Buttons: Cancel (Rollback) & Retry
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textLight : AppColors.textPrimary,
                      side: BorderSide(
                        color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
                    onPressed: onRetry,
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to display [SyncFailureDialog].
Future<void> showSyncFailureDialog({
  required BuildContext context,
  required VoidCallback onCancel,
  required VoidCallback onRetry,
  String title = 'Sync Failed',
  String message = 'Failed to sync changes with the database. Please check your network connection and try again.',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => SyncFailureDialog(
      title: title,
      message: message,
      onCancel: () {
        Navigator.of(dialogContext).pop();
        onCancel();
      },
      onRetry: () {
        Navigator.of(dialogContext).pop();
        onRetry();
      },
    ),
  );
}
