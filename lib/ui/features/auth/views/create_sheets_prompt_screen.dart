import 'package:flutter/material.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/animated_loading_window.dart';
import 'package:workout_tracker/ui/features/home/views/home_screen.dart';
import 'auth_screen.dart';

class CreateSheetsPromptScreen extends StatefulWidget {
  final DriveSheetsStatus status;

  const CreateSheetsPromptScreen({
    required this.status,
    super.key,
  });

  @override
  State<CreateSheetsPromptScreen> createState() =>
      _CreateSheetsPromptScreenState();
}

class _CreateSheetsPromptScreenState extends State<CreateSheetsPromptScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isCreating = false;

  Future<void> _handleCreateSheets() async {
    setState(() => _isCreating = true);
    try {
      await _driveService.createMissingSheets(
        createExerciseDb: !widget.status.exerciseDbExists,
        createDailyRecord: !widget.status.dailyRecordExists,
      );

      if (mounted) {
        // Successfully created sheets -> land on HomeScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create Excel sheets: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _driveService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating) {
      return const AnimatedLoadingWindow(
        message: 'Creating Excel Database Sheets...',
        subMessage: 'Setting up Exercise_DB.xlsx & Daily_record.xlsx on Google Drive',
      );
    }

    final missingExerciseDb = !widget.status.exerciseDbExists;
    final missingDailyRecord = !widget.status.dailyRecordExists;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_special_rounded,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Excel Database Setup Required',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'The required Excel sheets were not found in your "Workout Tracker" folder on Google Drive. Would you like to create them now?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // File Status Cards
              Expanded(
                child: ListView(
                  children: [
                    _buildSheetStatusCard(
                      title: 'Exercise_DB.xlsx',
                      subtitle: 'Columns: Id (GUID), exercise_name, body_part_target',
                      missing: missingExerciseDb,
                    ),
                    const SizedBox(height: 12),
                    _buildSheetStatusCard(
                      title: 'Daily_record.xlsx',
                      subtitle: 'Columns: ID, workout_ID, workout_name, Date, set, reps, RIR',
                      missing: missingDailyRecord,
                    ),
                  ],
                ),
              ),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _handleCreateSheets,
                  icon: const Icon(Icons.add_to_drive_rounded),
                  label: const Text(
                    'Create Excel Sheets Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _handleSignOut,
                  child: Text(
                    'Cancel & Sign Out',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetStatusCard({
    required String title,
    required String subtitle,
    required bool missing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: missing ? AppColors.warning.withValues(alpha: 0.4) : AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            missing ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: missing ? AppColors.warning : AppColors.success,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      missing ? 'NOT FOUND' : 'EXISTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: missing ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
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

