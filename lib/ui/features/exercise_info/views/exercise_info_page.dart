import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/data/services/google_drive_service.dart';
import 'package:workout_tracker/ui/features/workout_log/views/exercise_statistics_screen.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/compact_sync_button.dart';
import 'package:workout_tracker/ui/core/widgets/empty_state_widget.dart';
import 'package:workout_tracker/ui/core/widgets/filter_chip_bar.dart';
import 'package:workout_tracker/ui/core/widgets/search_bar_input.dart';
import 'package:workout_tracker/ui/core/widgets/sync_status_card.dart';
import 'widgets/add_exercise_modal.dart';
import 'widgets/exercise_item_tile.dart';

class ExerciseInfoPage extends StatefulWidget {
  const ExerciseInfoPage({super.key});

  @override
  State<ExerciseInfoPage> createState() => _ExerciseInfoPageState();
}

class _ExerciseInfoPageState extends State<ExerciseInfoPage> {
  final GoogleDriveService _driveService = GoogleDriveService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Exercise> _filteredExercises = [];
  bool _isLoading = true;
  bool _isSignedIn = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static const List<String> bodyParts = [
    'All',
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Forearms',
    'Legs',
    'Quadriceps',
    'Hamstrings',
    'Calves',
    'Core',
    'Glutes',
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadExercises();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadExercises() async {
    // 1. Immediately display cached exercises so UI renders without delay
    final cached = await _driveService.getExercises();
    if (mounted) {
      setState(() {
        _applyFilters();
        if (cached.isNotEmpty) _isLoading = false;
      });
    }

    try {
      final signedIn = await _driveService.isSignedIn();
      if (mounted) {
        setState(() => _isSignedIn = signedIn);
      }

      if (signedIn) {
        // Sync ONLY exercise DB from Drive (avoid downloading Daily_record.xlsx)
        await _driveService.syncExercisesFromDrive();
        await _driveService.getExercises();
      }

      if (mounted) {
        setState(() {
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading exercises: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    _filteredExercises = _driveService
        .queryExercises(
          category: _selectedCategory,
          searchQuery: _searchQuery,
        )
        .orderBy((e) => e.name)
        .toList();
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        _applyFilters();
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _applyFilters();
    });
  }

  Future<void> _handleSignIn() async {
    try {
      await _driveService.signIn();
      await _checkAuthAndLoadExercises();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _driveService.signOut();
    if (mounted) {
      setState(() => _isSignedIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out')),
      );
    }
  }

  Future<void> _addExercise(String name, String bodyPart) async {
    final nameLower = name.trim().toLowerCase();
    final isDuplicate = _driveService.queryExercises().toList().any((e) => e.name.toLowerCase() == nameLower);
    
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An exercise with this name already exists')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      await _driveService.addExercise(name, bodyPart);
      if (mounted) {
        setState(() {
          _applyFilters();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding exercise: $e')),
        );
      }
    }
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final relatedRecords = _driveService.queryDailyRecords(workoutId: exercise.guid).toList();
    if (relatedRecords.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning'),
          content: Text('There are ${relatedRecords.length} record(s) referencing "${exercise.name}". Deleting this exercise may leave orphaned records. Do you wish to proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise?'),
        content: Text('Are you sure you want to delete "${exercise.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await _driveService.deleteExercise(exercise.guid);
        if (mounted) {
          setState(() {
            _applyFilters();
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exercise "${exercise.name}" deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting exercise: $e')),
          );
        }
      }
    }
  }

  void _openAddExerciseModal() {
    final selectableBodyParts = bodyParts.where((bp) => bp != 'All').toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddExerciseModal(
        bodyParts: selectableBodyParts,
        onAdd: _addExercise,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Directory', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: CompactSyncButton(
                onPressed: _checkAuthAndLoadExercises,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExerciseModal,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Exercise', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Top Sync Status Banner
          Padding(
            padding: const EdgeInsets.all(16),
            child: SyncStatusCard(
              isSignedIn: _isSignedIn,
              userEmail: _driveService.currentUser?.email,
              onSignIn: _handleSignIn,
              onSignOut: _handleSignOut,
              onSyncNow: _checkAuthAndLoadExercises,
            ),
          ),

          // Search Bar Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchBarInput(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),
          const SizedBox(height: 12),

          // Filter Category Chips
          FilterChipBar(
            categories: bodyParts,
            selectedCategory: _selectedCategory,
            onSelected: _onCategorySelected,
          ),
          const SizedBox(height: 12),

          // Main Exercise List State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExercises.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.fitness_center_rounded,
                        title: 'No Exercises Found',
                        description: _searchQuery.isNotEmpty
                            ? 'No exercise matches "$_searchQuery". Try clearing your search.'
                            : 'No exercises added for $_selectedCategory yet.',
                        buttonText: 'Add New Exercise',
                        onButtonPressed: _openAddExerciseModal,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: _filteredExercises.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final exercise = _filteredExercises[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExerciseStatisticsScreen(initialExerciseGuid: exercise.guid),
                                ),
                              );
                            },
                            child: ExerciseItemTile(
                              exercise: exercise,
                              onDelete: () => _deleteExercise(exercise),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

