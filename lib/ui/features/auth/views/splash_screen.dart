import 'package:flutter/material.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/core/widgets/animated_loading_window.dart';
import 'package:workout_tracker/ui/features/home/views/home_screen.dart';
import 'auth_screen.dart';
import 'create_sheets_prompt_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();
  String _message = 'Initializing Workout Tracker...';
  String? _subMessage = 'Checking session state';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startValidationFlow();
    });
  }

  Future<void> _startValidationFlow() async {
    // Step 1: Check Google Sign-In Status
    setState(() {
      _message = 'Verifying Google Account...';
      _subMessage = 'Checking authentication status';
    });

    final isSignedIn = await _driveService.initializeIfSignedIn();

    if (!isSignedIn) {
      if (!mounted) return;
      // Not signed in -> Prompt user to sign in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    // Step 2: Check Google Drive Excel Database Sheets
    setState(() {
      _message = 'Validating Google Drive Databases...';
      _subMessage = 'Searching for Exercise_DB.xlsx & Daily_record.xlsx';
    });

    try {
      final status = await _driveService.checkSheetsExistence();

      if (!mounted) return;

      if (status.allExist) {
        // Both sheets exist -> Sync and land on HomeScreen
        setState(() {
          _message = 'Loading Dashboard...';
          _subMessage = 'Syncing exercise database';
        });
        await _driveService.syncFromDrive();

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // One or both sheets missing -> Prompt user to create them
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreateSheetsPromptScreen(status: status),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // In case of error (e.g. network issue), redirect to AuthScreen or retry
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedLoadingWindow(
      message: _message,
      subMessage: _subMessage,
    );
  }
}

