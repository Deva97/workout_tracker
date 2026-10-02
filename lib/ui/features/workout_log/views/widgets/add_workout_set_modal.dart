import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';

class AddWorkoutSetModal extends StatefulWidget {
  final List<Exercise> availableExercises;
  final Exercise? initialExercise;
  final int initialSetNumber;
  final Function(DailyRecord record, bool keepOpen) onSaveSet;
  final DailyRecord? editRecord;

  const AddWorkoutSetModal({
    required this.availableExercises,
    required this.onSaveSet,
    this.initialExercise,
    this.initialSetNumber = 1,
    this.editRecord,
    super.key,
  });

  @override
  State<AddWorkoutSetModal> createState() => _AddWorkoutSetModalState();
}

class _AddWorkoutSetModalState extends State<AddWorkoutSetModal> {
  final _formKey = GlobalKey<FormState>();

  Exercise? _selectedExercise;
  late TextEditingController _setController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  double _rirValue = 2.0;

  @override
  void initState() {
    super.initState();
    if (widget.editRecord != null) {
      final record = widget.editRecord!;
      _selectedExercise = widget.availableExercises.firstWhere(
        (e) => e.guid == record.workoutId,
        orElse: () => widget.initialExercise ?? widget.availableExercises.first,
      );
      _setController = TextEditingController(text: record.set.toString());
      _repsController = TextEditingController(text: record.reps.toString());
      _weightController = TextEditingController(text: record.weight.toString());
      _rirValue = record.rir;
    } else {
      _selectedExercise = widget.initialExercise ??
          (widget.availableExercises.isNotEmpty ? widget.availableExercises.first : null);
      _setController = TextEditingController(text: widget.initialSetNumber.toString());
      _repsController = TextEditingController(text: '10');
      _weightController = TextEditingController(text: '60.0');
      _rirValue = 2.0;
    }
  }

  @override
  void dispose() {
    _setController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _submitForm({required bool keepOpen}) {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exercise from Exercise_DB.')),
      );
      return;
    }

    final setNumber = int.parse(_setController.text.trim());
    final reps = int.parse(_repsController.text.trim());
    final weight = double.parse(_weightController.text.trim());
    final rir = _rirValue;

    final record = DailyRecord(
      id: widget.editRecord?.id ?? const Uuid().v4(),
      workoutId: _selectedExercise!.guid,
      workoutName: _selectedExercise!.name,
      date: widget.editRecord?.date ?? DateTime.now(),
      set: setNumber,
      reps: reps,
      rir: rir,
      weight: weight,
    );

    widget.onSaveSet(record, keepOpen);

    if (keepOpen) {
      setState(() {
        _setController.text = (setNumber + 1).toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set $setNumber added for ${_selectedExercise!.name}!'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editRecord != null ? 'Edit Workout Set' : 'Add Workout Set',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 16),
            const SizedBox(height: 6),

            // Exercise Selection Dropdown
            if (widget.editRecord != null && _selectedExercise != null)
              TextFormField(
                initialValue: _selectedExercise!.name,
                decoration: const InputDecoration(
                  labelText: 'Exercise',
                  prefixIcon: Icon(Icons.fitness_center_rounded, color: AppColors.primary),
                ),
                enabled: false,
              )
            else if (widget.availableExercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'No exercises found in Exercise_DB. Please add exercises in Exercise Directory first.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              )
            else
              DropdownButtonFormField<Exercise>(
                initialValue: _selectedExercise,
                decoration: const InputDecoration(
                  labelText: 'Exercise (from Exercise_DB)',
                  prefixIcon: Icon(Icons.fitness_center_rounded, color: AppColors.primary),
                ),
                isExpanded: true,
                items: widget.availableExercises.map((exercise) {
                  return DropdownMenuItem<Exercise>(
                    value: exercise,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        if (exercise.bodyPart.isNotEmpty)
                          StatusBadge.tag(
                            label: exercise.bodyPart.toUpperCase(),
                            color: AppColors.getMuscleColor(exercise.bodyPart),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                validator: (val) {
                  if (val == null) return 'Exercise is required';
                  return null;
                },
                onChanged: (val) {
                  setState(() {
                    _selectedExercise = val;
                  });
                },
              ),
            const SizedBox(height: 14),

            // Set Number & Reps Inputs Row
            Row(
              children: [
                // Set Number
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _setController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Set Number',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final n = int.tryParse(val.trim());
                      if (n == null || n <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Reps with Steppers
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDarkElevated : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, size: 20, color: AppColors.primary),
                          onPressed: () {
                            final current = int.tryParse(_repsController.text) ?? 10;
                            if (current > 1) {
                              _repsController.text = (current - 1).toString();
                            }
                          },
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _repsController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            decoration: const InputDecoration(
                              labelText: 'Reps',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              final n = int.tryParse(val.trim());
                              if (n == null || n <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
                          onPressed: () {
                            final current = int.tryParse(_repsController.text) ?? 10;
                            _repsController.text = (current + 1).toString();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Weight with Steppers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDarkElevated : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 20, color: AppColors.primary),
                    onPressed: () {
                      final current = double.tryParse(_weightController.text) ?? 60.0;
                      if (current >= 2.5) {
                        _weightController.text = (current - 2.5).toString();
                      }
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final n = double.tryParse(val.trim());
                        if (n == null || n < 0.0) return 'Must be >= 0';
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
                    onPressed: () {
                      final current = double.tryParse(_weightController.text) ?? 60.0;
                      _weightController.text = (current + 2.5).toString();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // RIR Slider
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDarkElevated : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reps in Reserve (RIR)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_rirValue.toStringAsFixed(1)} RIR',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _rirValue,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      label: _rirValue.toStringAsFixed(1),
                      onChanged: (val) {
                        setState(() {
                          _rirValue = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons Row
            Row(
              children: [
                if (widget.editRecord == null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.availableExercises.isEmpty
                          ? null
                          : () => _submitForm(keepOpen: true),
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text('Add & Next'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.availableExercises.isEmpty
                        ? null
                        : () => _submitForm(keepOpen: false),
                    icon: Icon(
                      widget.editRecord != null ? Icons.update_rounded : Icons.check_circle_rounded,
                      size: 18,
                    ),
                    label: Text(widget.editRecord != null ? 'Update Set' : 'Save Set'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
