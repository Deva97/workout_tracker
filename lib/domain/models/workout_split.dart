/// Workout split definitions, constants, and validation rules.
class WorkoutSplit {
  static const String broSplit = 'Bro Split';
  static const String pullPushSplit = 'Pull-Push Split';
  static const String anteriorPosteriorSplit = 'Anterior-Posterior Split';
  static const String fullBodySplit = 'Full Body Split';

  static const List<String> splitOptions = [
    broSplit,
    pullPushSplit,
    anteriorPosteriorSplit,
    fullBodySplit,
  ];

  static const List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> broSplitMuscleOptions = [
    'Legs',
    'Shoulders',
    'Triceps',
    'Chest',
    'Back',
    'Biceps',
    'Core',
    'Abs',
    'Glutes',
    'Calves',
    'Forearms',
  ];

  /// Get available workout exercise/category options for a given split
  static List<String> getWorkoutOptions(String split) {
    switch (split) {
      case broSplit:
        return broSplitMuscleOptions;
      case pullPushSplit:
        return const ['Push', 'Pull'];
      case anteriorPosteriorSplit:
        return const ['Anterior', 'Posterior'];
      case fullBodySplit:
        return const ['Full Body'];
      default:
        return const [];
    }
  }

  /// Default suggested workout days per week for a given split
  static int getDefaultTargetDays(String split) {
    switch (split) {
      case pullPushSplit:
        return 4;
      case anteriorPosteriorSplit:
        return 4;
      case fullBodySplit:
        return 3;
      case broSplit:
      default:
        return 5;
    }
  }

  /// Legacy maximum allowed workout days per week.
  /// Note: Splits now support dynamic user-selected workout days (1 to 7).
  static int? getMaximumWorkoutDays(String split) {
    switch (split) {
      case pullPushSplit:
        return 4;
      case anteriorPosteriorSplit:
        return 4;
      case fullBodySplit:
        return 3;
      default:
        return null;
    }
  }
}
